// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: StepShotsCodeBuilder
// **************************************************************************

import 'package:flutter_test/flutter_test.dart';
import '../support/step_shots.dart';

import 'app_steps.dart';

runFeatures() {
  final steps = AppSteps();
  group('Practice Screen', () {
    testWidgets('User practices a noun', (WidgetTester widgetTester) async {
      await step(
        widgetTester,
        'Practice Screen',
        'User practices a noun',
        'Given the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User practices a noun',
        'When I am on the "home" screen',
        steps.iAmOnScreen(widgetTester, 'home'),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User practices a noun',
        'And I tap on "home.nouns.button"',
        steps.iTapOn(widgetTester, 'home.nouns.button'),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User practices a noun',
        'Then I should see a practice screen with a word type',
        steps.iShouldSeePracticeScreen(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User practices a noun',
        'And I should see input fields for forms',
        steps.iShouldSeeInputFields(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User practices a noun',
        'And I take a screenshot named "practice_noun_initial"',
        steps.iTakeScreenshot(widgetTester, 'practice_noun_initial'),
      );
    });
    testWidgets('User checks answers for a noun', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Practice Screen',
        'User checks answers for a noun',
        'Given the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User checks answers for a noun',
        'When I am on the "home" screen',
        steps.iAmOnScreen(widgetTester, 'home'),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User checks answers for a noun',
        'And I tap on "home.nouns.button"',
        steps.iTapOn(widgetTester, 'home.nouns.button'),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User checks answers for a noun',
        'And I wait for the practice screen to load',
        steps.iWaitForPracticeScreen(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User checks answers for a noun',
        'And I enter answers in the input fields',
        steps.iEnterAnswers(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User checks answers for a noun',
        'And I tap on check',
        steps.iTapOnCheck(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User checks answers for a noun',
        'Then I should see validation results',
        steps.iShouldSeeValidationResults(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User checks answers for a noun',
        'And I take a screenshot named "practice_noun_checked"',
        steps.iTakeScreenshot(widgetTester, 'practice_noun_checked'),
      );
    });
    testWidgets('User rates a card after practice', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Practice Screen',
        'User rates a card after practice',
        'Given the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User rates a card after practice',
        'When I am on the "home" screen',
        steps.iAmOnScreen(widgetTester, 'home'),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User rates a card after practice',
        'And I tap on "home.nouns.button"',
        steps.iTapOn(widgetTester, 'home.nouns.button'),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User rates a card after practice',
        'And I wait for the practice screen to load',
        steps.iWaitForPracticeScreen(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User rates a card after practice',
        'And I enter answers in the input fields',
        steps.iEnterAnswers(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User rates a card after practice',
        'And I tap on check',
        steps.iTapOnCheck(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User rates a card after practice',
        'And I wait for rating buttons to appear',
        steps.iWaitForRatingButtons(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User rates a card after practice',
        'Then I should see rating buttons',
        steps.iShouldSeeRatingButtons(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User rates a card after practice',
        'And I take a screenshot named "practice_noun_rating"',
        steps.iTakeScreenshot(widgetTester, 'practice_noun_rating'),
      );
    });
    testWidgets('User sees an explanation for a wrong answer', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Practice Screen',
        'User sees an explanation for a wrong answer',
        'Given the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User sees an explanation for a wrong answer',
        'When I am on the "home" screen',
        steps.iAmOnScreen(widgetTester, 'home'),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User sees an explanation for a wrong answer',
        'And I tap on "home.nouns.button"',
        steps.iTapOn(widgetTester, 'home.nouns.button'),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User sees an explanation for a wrong answer',
        'And I wait for the practice screen to load',
        steps.iWaitForPracticeScreen(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User sees an explanation for a wrong answer',
        'And I enter "zzz" in the input fields',
        steps.iEnterInInputFields(widgetTester, 'zzz'),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User sees an explanation for a wrong answer',
        'And I tap on check',
        steps.iTapOnCheck(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User sees an explanation for a wrong answer',
        'Then I should see an explanation for a wrong answer',
        steps.iShouldSeeAnExplanation(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User sees an explanation for a wrong answer',
        'And I take a screenshot named "practice_noun_explanation"',
        steps.iTakeScreenshot(widgetTester, 'practice_noun_explanation'),
      );
    });
    testWidgets('User practices a verb', (WidgetTester widgetTester) async {
      await step(
        widgetTester,
        'Practice Screen',
        'User practices a verb',
        'Given the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User practices a verb',
        'When I am on the "home" screen',
        steps.iAmOnScreen(widgetTester, 'home'),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User practices a verb',
        'And I tap on "home.verbs.button"',
        steps.iTapOn(widgetTester, 'home.verbs.button'),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User practices a verb',
        'Then I should see a practice screen with a word type',
        steps.iShouldSeePracticeScreen(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User practices a verb',
        'And I should see input fields for forms',
        steps.iShouldSeeInputFields(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'User practices a verb',
        'And I take a screenshot named "practice_verb_initial"',
        steps.iTakeScreenshot(widgetTester, 'practice_verb_initial'),
      );
    });
    testWidgets('Each right form not shown in the heading earns 3 coins', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Practice Screen',
        'Each right form not shown in the heading earns 3 coins',
        'Given I have 20 coins',
        steps.iHaveCoins(widgetTester, 20),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'Each right form not shown in the heading earns 3 coins',
        'And the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'Each right form not shown in the heading earns 3 coins',
        'When I am on the "home" screen',
        steps.iAmOnScreen(widgetTester, 'home'),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'Each right form not shown in the heading earns 3 coins',
        'And I tap on "home.nouns.button"',
        steps.iTapOn(widgetTester, 'home.nouns.button'),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'Each right form not shown in the heading earns 3 coins',
        'And I wait for the practice screen to load',
        steps.iWaitForPracticeScreen(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'Each right form not shown in the heading earns 3 coins',
        'And I enter the right answers in 2 input fields',
        steps.iEnterRightAnswers(widgetTester, 2),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'Each right form not shown in the heading earns 3 coins',
        'And I tap on check',
        steps.iTapOnCheck(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'Each right form not shown in the heading earns 3 coins',
        'And I go back home',
        steps.iLeaveTheRound(widgetTester),
      );
      await step(
        widgetTester,
        'Practice Screen',
        'Each right form not shown in the heading earns 3 coins',
        'Then I should have 20 coins plus 3 per paying choice',
        steps.iShouldHaveCoinsPerChoice(widgetTester, 20, 3),
      );
    });
  });
  group('Focus on a word group', () {
    testWidgets(
      'A round with the focus "Unregelmäßige Verben" asks only irregular verbs',
      (WidgetTester widgetTester) async {
        await step(
          widgetTester,
          'Focus on a word group',
          'A round with the focus "Unregelmäßige Verben" asks only irregular verbs',
          'Given the device language is German',
          steps.theDeviceLanguageIsGerman(widgetTester),
        );
        await step(
          widgetTester,
          'Focus on a word group',
          'A round with the focus "Unregelmäßige Verben" asks only irregular verbs',
          'And the app is running',
          steps.theAppIsRunning(widgetTester),
        );
        await step(
          widgetTester,
          'Focus on a word group',
          'A round with the focus "Unregelmäßige Verben" asks only irregular verbs',
          'When I start a round with the focus "Unregelmäßige Verben"',
          steps.iStartAFocusedRound(widgetTester, 'Unregelmäßige Verben'),
        );
        await step(
          widgetTester,
          'Focus on a word group',
          'A round with the focus "Unregelmäßige Verben" asks only irregular verbs',
          'Then every task of the round asks an irregular verb',
          steps.everyTaskAsksAnIrregularVerb(widgetTester),
        );
      },
    );
  });
  group('Store pictures', () {
    testWidgets('Home screen with town and coins', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Store pictures',
        'Home screen with town and coins',
        'Given the device language is the store locale',
        steps.theDeviceLanguageIsTheStoreLocale(widgetTester),
      );
      await step(
        widgetTester,
        'Store pictures',
        'Home screen with town and coins',
        'And I have 1250 coins',
        steps.iHaveCoins(widgetTester, 1250),
      );
      await step(
        widgetTester,
        'Store pictures',
        'Home screen with town and coins',
        'And I have built 5 buildings',
        steps.iHaveBuilt(widgetTester, 5),
      );
      await step(
        widgetTester,
        'Store pictures',
        'Home screen with town and coins',
        'And the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Store pictures',
        'Home screen with town and coins',
        'Then the screen looks like "store-1100-startseite.png"',
        steps.theScreenLooksLike(widgetTester, 'store-1100-startseite.png'),
      );
    });
    testWidgets('A practice task', (WidgetTester widgetTester) async {
      await step(
        widgetTester,
        'Store pictures',
        'A practice task',
        'Given the device language is the store locale',
        steps.theDeviceLanguageIsTheStoreLocale(widgetTester),
      );
      await step(
        widgetTester,
        'Store pictures',
        'A practice task',
        'And I have 1250 coins',
        steps.iHaveCoins(widgetTester, 1250),
      );
      await step(
        widgetTester,
        'Store pictures',
        'A practice task',
        'And I have built 5 buildings',
        steps.iHaveBuilt(widgetTester, 5),
      );
      await step(
        widgetTester,
        'Store pictures',
        'A practice task',
        'And the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Store pictures',
        'A practice task',
        'When I start a round',
        steps.iStartARound(widgetTester),
      );
      await step(
        widgetTester,
        'Store pictures',
        'A practice task',
        'Then the screen looks like "store-1200-aufgabe.png"',
        steps.theScreenLooksLike(widgetTester, 'store-1200-aufgabe.png'),
      );
    });
    testWidgets('The course position settings', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Store pictures',
        'The course position settings',
        'Given the device language is the store locale',
        steps.theDeviceLanguageIsTheStoreLocale(widgetTester),
      );
      await step(
        widgetTester,
        'Store pictures',
        'The course position settings',
        'And I have 1250 coins',
        steps.iHaveCoins(widgetTester, 1250),
      );
      await step(
        widgetTester,
        'Store pictures',
        'The course position settings',
        'And I have built 5 buildings',
        steps.iHaveBuilt(widgetTester, 5),
      );
      await step(
        widgetTester,
        'Store pictures',
        'The course position settings',
        'And the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Store pictures',
        'The course position settings',
        'When I open the drawer',
        steps.iOpenTheDrawer(widgetTester),
      );
      await step(
        widgetTester,
        'Store pictures',
        'The course position settings',
        'And I tap on "drawer.settings"',
        steps.iTapOn(widgetTester, 'drawer.settings'),
      );
      await step(
        widgetTester,
        'Store pictures',
        'The course position settings',
        'Then the screen looks like "store-1300-kursstand.png"',
        steps.theScreenLooksLike(widgetTester, 'store-1300-kursstand.png'),
      );
    });
    testWidgets('The town shop', (WidgetTester widgetTester) async {
      await step(
        widgetTester,
        'Store pictures',
        'The town shop',
        'Given the device language is the store locale',
        steps.theDeviceLanguageIsTheStoreLocale(widgetTester),
      );
      await step(
        widgetTester,
        'Store pictures',
        'The town shop',
        'And I have 1250 coins',
        steps.iHaveCoins(widgetTester, 1250),
      );
      await step(
        widgetTester,
        'Store pictures',
        'The town shop',
        'And I have built 5 buildings',
        steps.iHaveBuilt(widgetTester, 5),
      );
      await step(
        widgetTester,
        'Store pictures',
        'The town shop',
        'And the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Store pictures',
        'The town shop',
        'When I tap on "home.town"',
        steps.iTapOn(widgetTester, 'home.town'),
      );
      await step(
        widgetTester,
        'Store pictures',
        'The town shop',
        'And I tap on "town.build"',
        steps.iTapOn(widgetTester, 'town.build'),
      );
      await step(
        widgetTester,
        'Store pictures',
        'The town shop',
        'Then the screen looks like "store-1400-laden.png"',
        steps.theScreenLooksLike(widgetTester, 'store-1400-laden.png'),
      );
    });
  });
  group('Home Screen', () {
    testWidgets('User sees home screen with practice options', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Home Screen',
        'User sees home screen with practice options',
        'Given the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Home Screen',
        'User sees home screen with practice options',
        'When I am on the "home" screen',
        steps.iAmOnScreen(widgetTester, 'home'),
      );
      await step(
        widgetTester,
        'Home Screen',
        'User sees home screen with practice options',
        'Then I should see "app.title" in the app bar',
        steps.iShouldSeeInAppBar(widgetTester, 'app.title'),
      );
      await step(
        widgetTester,
        'Home Screen',
        'User sees home screen with practice options',
        'And I should see a button with text "home.nouns.button"',
        steps.iShouldSeeButtonWithText(widgetTester, 'home.nouns.button'),
      );
      await step(
        widgetTester,
        'Home Screen',
        'User sees home screen with practice options',
        'And I should see a button with text "home.verbs.button"',
        steps.iShouldSeeButtonWithText(widgetTester, 'home.verbs.button'),
      );
      await step(
        widgetTester,
        'Home Screen',
        'User sees home screen with practice options',
        'And I should see a button with text "home.wordClassification.button"',
        steps.iShouldSeeButtonWithText(
          widgetTester,
          'home.wordClassification.button',
        ),
      );
      await step(
        widgetTester,
        'Home Screen',
        'User sees home screen with practice options',
        'And I take a screenshot named "home_screen"',
        steps.iTakeScreenshot(widgetTester, 'home_screen'),
      );
    });
    testWidgets('User opens drawer from home screen', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Home Screen',
        'User opens drawer from home screen',
        'Given the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Home Screen',
        'User opens drawer from home screen',
        'When I am on the "home" screen',
        steps.iAmOnScreen(widgetTester, 'home'),
      );
      await step(
        widgetTester,
        'Home Screen',
        'User opens drawer from home screen',
        'And I open the drawer',
        steps.iOpenTheDrawer(widgetTester),
      );
      await step(
        widgetTester,
        'Home Screen',
        'User opens drawer from home screen',
        'Then I should see "drawer.settings" in the drawer',
        steps.iShouldSeeInDrawer(widgetTester, 'drawer.settings'),
      );
      await step(
        widgetTester,
        'Home Screen',
        'User opens drawer from home screen',
        'And I take a screenshot named "home_screen_drawer"',
        steps.iTakeScreenshot(widgetTester, 'home_screen_drawer'),
      );
    });
    testWidgets('User navigates to settings from drawer', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Home Screen',
        'User navigates to settings from drawer',
        'Given the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Home Screen',
        'User navigates to settings from drawer',
        'When I am on the "home" screen',
        steps.iAmOnScreen(widgetTester, 'home'),
      );
      await step(
        widgetTester,
        'Home Screen',
        'User navigates to settings from drawer',
        'And I open the drawer',
        steps.iOpenTheDrawer(widgetTester),
      );
      await step(
        widgetTester,
        'Home Screen',
        'User navigates to settings from drawer',
        'And I tap on "drawer.settings"',
        steps.iTapOn(widgetTester, 'drawer.settings'),
      );
      await step(
        widgetTester,
        'Home Screen',
        'User navigates to settings from drawer',
        'Then I should see "settings.title" in the app bar',
        steps.iShouldSeeInAppBar(widgetTester, 'settings.title'),
      );
      await step(
        widgetTester,
        'Home Screen',
        'User navigates to settings from drawer',
        'And I take a screenshot named "settings_screen"',
        steps.iTakeScreenshot(widgetTester, 'settings_screen'),
      );
    });
  });
  group('Rewards', () {
    testWidgets('A right answer earns 10 coins', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Rewards',
        'A right answer earns 10 coins',
        'Given I have 20 coins',
        steps.iHaveCoins(widgetTester, 20),
      );
      await step(
        widgetTester,
        'Rewards',
        'A right answer earns 10 coins',
        'And the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'A right answer earns 10 coins',
        'When I start a round',
        steps.iStartARound(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'A right answer earns 10 coins',
        'And I answer the task correctly',
        steps.iAnswerCorrectly(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'A right answer earns 10 coins',
        'And I leave the round',
        steps.iLeaveTheRound(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'A right answer earns 10 coins',
        'Then I should have 30 coins',
        steps.iShouldHaveCoins(widgetTester, 30),
      );
    });
    testWidgets('A task answered right on the second try earns 5 coins', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Rewards',
        'A task answered right on the second try earns 5 coins',
        'Given I have 0 coins',
        steps.iHaveCoins(widgetTester, 0),
      );
      await step(
        widgetTester,
        'Rewards',
        'A task answered right on the second try earns 5 coins',
        'And the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'A task answered right on the second try earns 5 coins',
        'When I start a round',
        steps.iStartARound(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'A task answered right on the second try earns 5 coins',
        'And I answer the task wrongly',
        steps.iAnswerWrongly(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'A task answered right on the second try earns 5 coins',
        'And I finish the round',
        steps.iFinishTheRound(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'A task answered right on the second try earns 5 coins',
        'And I leave the round',
        steps.iLeaveTheRound(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'A task answered right on the second try earns 5 coins',
        'Then I should have 95 coins',
        steps.iShouldHaveCoins(widgetTester, 95),
      );
    });
    testWidgets('Finishing a round adds no building', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Rewards',
        'Finishing a round adds no building',
        'Given I have built 2 buildings',
        steps.iHaveBuilt(widgetTester, 2),
      );
      await step(
        widgetTester,
        'Rewards',
        'Finishing a round adds no building',
        'And the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'Finishing a round adds no building',
        'When I start a round',
        steps.iStartARound(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'Finishing a round adds no building',
        'And I finish the round',
        steps.iFinishTheRound(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'Finishing a round adds no building',
        'And I leave the round',
        steps.iLeaveTheRound(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'Finishing a round adds no building',
        'Then my town should have 2 buildings',
        steps.myTownHasBuildings(widgetTester, 2),
      );
    });
    testWidgets('A building bought with enough coins appears in the town', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Rewards',
        'A building bought with enough coins appears in the town',
        'Given I have 900 coins',
        steps.iHaveCoins(widgetTester, 900),
      );
      await step(
        widgetTester,
        'Rewards',
        'A building bought with enough coins appears in the town',
        'And I have built "domus, fons"',
        steps.iHaveBuiltIds(widgetTester, 'domus, fons'),
      );
      await step(
        widgetTester,
        'Rewards',
        'A building bought with enough coins appears in the town',
        'And the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'A building bought with enough coins appears in the town',
        'When I buy "templum"',
        steps.iBuy(widgetTester, 'templum'),
      );
      await step(
        widgetTester,
        'Rewards',
        'A building bought with enough coins appears in the town',
        'Then I should have 300 coins',
        steps.iShouldHaveCoins(widgetTester, 300),
      );
      await step(
        widgetTester,
        'Rewards',
        'A building bought with enough coins appears in the town',
        'And the town shows "templum"',
        steps.theTownShows(widgetTester, 'templum'),
      );
    });
    testWidgets('A building that costs more than my coins cannot be bought', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Rewards',
        'A building that costs more than my coins cannot be bought',
        'Given I have 500 coins',
        steps.iHaveCoins(widgetTester, 500),
      );
      await step(
        widgetTester,
        'Rewards',
        'A building that costs more than my coins cannot be bought',
        'And I have built "domus, fons"',
        steps.iHaveBuiltIds(widgetTester, 'domus, fons'),
      );
      await step(
        widgetTester,
        'Rewards',
        'A building that costs more than my coins cannot be bought',
        'And the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'A building that costs more than my coins cannot be bought',
        'Then I cannot buy "templum"',
        steps.iCannotBuy(widgetTester, 'templum'),
      );
    });
    testWidgets('A reward I switched off is not shown', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Rewards',
        'A reward I switched off is not shown',
        'Given I switched the "points" reward off',
        steps.iSwitchedRewardOff(widgetTester, 'points'),
      );
      await step(
        widgetTester,
        'Rewards',
        'A reward I switched off is not shown',
        'And I have 20 coins',
        steps.iHaveCoins(widgetTester, 20),
      );
      await step(
        widgetTester,
        'Rewards',
        'A reward I switched off is not shown',
        'And the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'A reward I switched off is not shown',
        'Then I should see no coins',
        steps.iShouldSeeNoCoins(widgetTester),
      );
    });
    testWidgets('A town I switched off is not shown', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Rewards',
        'A town I switched off is not shown',
        'Given I switched the "town" reward off',
        steps.iSwitchedRewardOff(widgetTester, 'town'),
      );
      await step(
        widgetTester,
        'Rewards',
        'A town I switched off is not shown',
        'And I have built 2 buildings',
        steps.iHaveBuilt(widgetTester, 2),
      );
      await step(
        widgetTester,
        'Rewards',
        'A town I switched off is not shown',
        'And the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'A town I switched off is not shown',
        'Then I should see no town',
        steps.iShouldSeeNoTown(widgetTester),
      );
    });
    testWidgets('Coins earned after buying the bank count double', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Rewards',
        'Coins earned after buying the bank count double',
        'Given I have 1020 coins',
        steps.iHaveCoins(widgetTester, 1020),
      );
      await step(
        widgetTester,
        'Rewards',
        'Coins earned after buying the bank count double',
        'And I have built "portus, bibliotheca, murus"',
        steps.iHaveBuiltIds(widgetTester, 'portus, bibliotheca, murus'),
      );
      await step(
        widgetTester,
        'Rewards',
        'Coins earned after buying the bank count double',
        'And the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'Coins earned after buying the bank count double',
        'When I buy "argentaria"',
        steps.iBuy(widgetTester, 'argentaria'),
      );
      await step(
        widgetTester,
        'Rewards',
        'Coins earned after buying the bank count double',
        'And I start a round',
        steps.iStartARound(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'Coins earned after buying the bank count double',
        'And I answer the task correctly',
        steps.iAnswerCorrectly(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'Coins earned after buying the bank count double',
        'And I leave the round',
        steps.iLeaveTheRound(widgetTester),
      );
      await step(
        widgetTester,
        'Rewards',
        'Coins earned after buying the bank count double',
        'Then I should have 40 coins',
        steps.iShouldHaveCoins(widgetTester, 40),
      );
    });
  });
  group('Word Classification', () {
    testWidgets('User opens word classification screen', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Word Classification',
        'User opens word classification screen',
        'Given the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Word Classification',
        'User opens word classification screen',
        'When I am on the "home" screen',
        steps.iAmOnScreen(widgetTester, 'home'),
      );
      await step(
        widgetTester,
        'Word Classification',
        'User opens word classification screen',
        'And I tap on "home.wordClassification.button"',
        steps.iTapOn(widgetTester, 'home.wordClassification.button'),
      );
      await step(
        widgetTester,
        'Word Classification',
        'User opens word classification screen',
        'Then I should see "wordClassification.declension" or "wordClassification.conjugation" in the title',
        steps.iShouldSeeInTitle(
          widgetTester,
          'wordClassification.declension',
          'wordClassification.conjugation',
        ),
      );
      await step(
        widgetTester,
        'Word Classification',
        'User opens word classification screen',
        'And I should see a word displayed',
        steps.iShouldSeeWordDisplayed(widgetTester),
      );
      await step(
        widgetTester,
        'Word Classification',
        'User opens word classification screen',
        'And I should see classification dropdowns',
        steps.iShouldSeeClassificationDropdowns(widgetTester),
      );
      await step(
        widgetTester,
        'Word Classification',
        'User opens word classification screen',
        'And I take a screenshot named "word_classification_initial"',
        steps.iTakeScreenshot(widgetTester, 'word_classification_initial'),
      );
    });
    testWidgets('User classifies a word correctly', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Word Classification',
        'User classifies a word correctly',
        'Given the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Word Classification',
        'User classifies a word correctly',
        'When I am on the "home" screen',
        steps.iAmOnScreen(widgetTester, 'home'),
      );
      await step(
        widgetTester,
        'Word Classification',
        'User classifies a word correctly',
        'And I tap on "home.wordClassification.button"',
        steps.iTapOn(widgetTester, 'home.wordClassification.button'),
      );
      await step(
        widgetTester,
        'Word Classification',
        'User classifies a word correctly',
        'And I wait for "the word" to load',
        steps.iWaitForToLoad(widgetTester, 'the word'),
      );
      await step(
        widgetTester,
        'Word Classification',
        'User classifies a word correctly',
        'And I select classification options',
        steps.iSelectClassificationOptions(widgetTester),
      );
      await step(
        widgetTester,
        'Word Classification',
        'User classifies a word correctly',
        'And I tap on "wordClassification.check.button"',
        steps.iTapOn(widgetTester, 'wordClassification.check.button'),
      );
      await step(
        widgetTester,
        'Word Classification',
        'User classifies a word correctly',
        'Then I should see validation feedback',
        steps.iShouldSeeValidationFeedback(widgetTester),
      );
      await step(
        widgetTester,
        'Word Classification',
        'User classifies a word correctly',
        'And I take a screenshot named "word_classification_checked"',
        steps.iTakeScreenshot(widgetTester, 'word_classification_checked'),
      );
    });
    testWidgets('A right classification earns 3 coins per dropdown', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Word Classification',
        'A right classification earns 3 coins per dropdown',
        'Given I have 20 coins',
        steps.iHaveCoins(widgetTester, 20),
      );
      await step(
        widgetTester,
        'Word Classification',
        'A right classification earns 3 coins per dropdown',
        'And the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Word Classification',
        'A right classification earns 3 coins per dropdown',
        'When I am on the "home" screen',
        steps.iAmOnScreen(widgetTester, 'home'),
      );
      await step(
        widgetTester,
        'Word Classification',
        'A right classification earns 3 coins per dropdown',
        'And I tap on "home.wordClassification.button"',
        steps.iTapOn(widgetTester, 'home.wordClassification.button'),
      );
      await step(
        widgetTester,
        'Word Classification',
        'A right classification earns 3 coins per dropdown',
        'And I wait for "the word" to load',
        steps.iWaitForToLoad(widgetTester, 'the word'),
      );
      await step(
        widgetTester,
        'Word Classification',
        'A right classification earns 3 coins per dropdown',
        'And I classify the word correctly',
        steps.iClassifyCorrectly(widgetTester),
      );
      await step(
        widgetTester,
        'Word Classification',
        'A right classification earns 3 coins per dropdown',
        'And I tap on "wordClassification.check.button"',
        steps.iTapOn(widgetTester, 'wordClassification.check.button'),
      );
      await step(
        widgetTester,
        'Word Classification',
        'A right classification earns 3 coins per dropdown',
        'And I go back home',
        steps.iLeaveTheRound(widgetTester),
      );
      await step(
        widgetTester,
        'Word Classification',
        'A right classification earns 3 coins per dropdown',
        'Then I should have 20 coins plus 3 per paying choice',
        steps.iShouldHaveCoinsPerChoice(widgetTester, 20, 3),
      );
    });
  });
  group('Settings Screen', () {
    testWidgets('User views settings screen', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Settings Screen',
        'User views settings screen',
        'Given the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Settings Screen',
        'User views settings screen',
        'When I am on the "home" screen',
        steps.iAmOnScreen(widgetTester, 'home'),
      );
      await step(
        widgetTester,
        'Settings Screen',
        'User views settings screen',
        'And I open the drawer',
        steps.iOpenTheDrawer(widgetTester),
      );
      await step(
        widgetTester,
        'Settings Screen',
        'User views settings screen',
        'And I tap on "drawer.settings"',
        steps.iTapOn(widgetTester, 'drawer.settings'),
      );
      await step(
        widgetTester,
        'Settings Screen',
        'User views settings screen',
        'Then I should see "settings.section.kursstand" section',
        steps.iShouldSeeSection(widgetTester, 'settings.section.kursstand'),
      );
      await step(
        widgetTester,
        'Settings Screen',
        'User views settings screen',
        'And I should see "settings.tile.words" section',
        steps.iShouldSeeSection(widgetTester, 'settings.tile.words'),
      );
      await step(
        widgetTester,
        'Settings Screen',
        'User views settings screen',
        'And I should see "settings.tile.nouns" section',
        steps.iShouldSeeSection(widgetTester, 'settings.tile.nouns'),
      );
      await step(
        widgetTester,
        'Settings Screen',
        'User views settings screen',
        'And I take a screenshot named "settings_screen_full"',
        steps.iTakeScreenshot(widgetTester, 'settings_screen_full'),
      );
    });
    testWidgets('User toggles a form setting', (
      WidgetTester widgetTester,
    ) async {
      await step(
        widgetTester,
        'Settings Screen',
        'User toggles a form setting',
        'Given the app is running',
        steps.theAppIsRunning(widgetTester),
      );
      await step(
        widgetTester,
        'Settings Screen',
        'User toggles a form setting',
        'When I am on the "home" screen',
        steps.iAmOnScreen(widgetTester, 'home'),
      );
      await step(
        widgetTester,
        'Settings Screen',
        'User toggles a form setting',
        'And I open the drawer',
        steps.iOpenTheDrawer(widgetTester),
      );
      await step(
        widgetTester,
        'Settings Screen',
        'User toggles a form setting',
        'And I tap on "drawer.settings"',
        steps.iTapOn(widgetTester, 'drawer.settings'),
      );
      await step(
        widgetTester,
        'Settings Screen',
        'User toggles a form setting',
        'And I tap on "settings.tile.nouns"',
        steps.iTapOn(widgetTester, 'settings.tile.nouns'),
      );
      await step(
        widgetTester,
        'Settings Screen',
        'User toggles a form setting',
        'And I wait for "settings" to load',
        steps.iWaitForToLoad(widgetTester, 'settings'),
      );
      await step(
        widgetTester,
        'Settings Screen',
        'User toggles a form setting',
        'And I toggle a form checkbox',
        steps.iToggleCheckbox(widgetTester),
      );
      await step(
        widgetTester,
        'Settings Screen',
        'User toggles a form setting',
        'Then the checkbox state should change',
        steps.checkboxStateShouldChange(widgetTester),
      );
      await step(
        widgetTester,
        'Settings Screen',
        'User toggles a form setting',
        'And I take a screenshot named "settings_screen_toggled"',
        steps.iTakeScreenshot(widgetTester, 'settings_screen_toggled'),
      );
    });
  });
}
