Feature: Home Screen
  As a user
  I want to see the home screen with practice options
  So that I can choose what to practice

  Scenario: User sees home screen with practice options
    Given the app is running
    When I am on the "home" screen
    Then I should see "app.title" in the app bar
    And I should see a button with text "home.nouns.button"
    And I should see a button with text "home.verbs.button"
    And I should see a button with text "home.wordClassification.button"
    And I take a screenshot named "home_screen"

  Scenario: User opens drawer from home screen
    Given the app is running
    When I am on the "home" screen
    And I open the drawer
    Then I should see "drawer.settings" in the drawer
    And I take a screenshot named "home_screen_drawer"

  Scenario: User navigates to settings from drawer
    Given the app is running
    When I am on the "home" screen
    And I open the drawer
    And I tap on "drawer.settings"
    Then I should see "settings.title" in the app bar
    And I take a screenshot named "settings_screen"
