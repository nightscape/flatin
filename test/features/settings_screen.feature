Feature: Settings Screen
  As a user
  I want to configure which forms to practice
  So that I can customize my learning experience

  Scenario: User views settings screen
    Given the app is running
    When I am on the "home" screen
    And I open the drawer
    And I tap on "drawer.settings"
    Then I should see "settings.section.nouns" section
    And I should see "settings.section.verbs" section
    And I should see checkboxes for form options
    And I take a screenshot named "settings_screen_full"

  Scenario: User toggles a form setting
    Given the app is running
    When I am on the "home" screen
    And I open the drawer
    And I tap on "drawer.settings"
    And I wait for "settings" to load
    And I toggle a form checkbox
    Then the checkbox state should change
    And I take a screenshot named "settings_screen_toggled"
