Feature: Practice Screen
  As a user
  I want to practice Latin nouns and verbs
  So that I can improve my Latin skills

  Scenario: User practices a noun
    Given the app is running
    When I am on the home screen
    And I tap on "home nouns button"
    Then I should see a practice screen with a word type
    And I should see input fields for forms
    And I take a screenshot named "practice_noun_initial"

  Scenario: User checks answers for a noun
    Given the app is running
    When I am on the home screen
    And I tap on "home nouns button"
    And I wait for the practice screen to load
    And I enter answers in the input fields
    And I tap on check
    Then I should see validation results
    And I take a screenshot named "practice_noun_checked"

  Scenario: User rates a card after practice
    Given the app is running
    When I am on the home screen
    And I tap on "home nouns button"
    And I wait for the practice screen to load
    And I enter answers in the input fields
    And I tap on check
    And I wait for rating buttons to appear
    Then I should see rating buttons
    And I take a screenshot named "practice_noun_rating"

  Scenario: User practices a verb
    Given the app is running
    When I am on the home screen
    And I tap on "home verbs button"
    Then I should see a practice screen with a word type
    And I should see input fields for forms
    And I take a screenshot named "practice_verb_initial"

